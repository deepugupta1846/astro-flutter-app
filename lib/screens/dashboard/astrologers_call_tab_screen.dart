import 'package:flutter/material.dart';

import '../../core/api/astrologer_api.dart';
import '../../core/api/consultation_api.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_primary_button.dart';
import '../consultation/consultation_room_screen.dart';
import 'astrologer_public_views.dart';

/// Call tab: same astrologer discovery as Home (search, live strip, feed cards).
class AstrologersCallTabScreen extends StatefulWidget {
  const AstrologersCallTabScreen({super.key});

  @override
  State<AstrologersCallTabScreen> createState() => _AstrologersCallTabScreenState();
}

class _AstrologersCallTabScreenState extends State<AstrologersCallTabScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _astrologers = [];
  bool _astroLoading = true;
  String? _astroError;

  List<Map<String, dynamic>> _recentCalls = [];
  bool _callsLoading = true;
  String? _callsError;

  List<Map<String, dynamic>> get _filteredAstrologers {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _astrologers;
    return _astrologers.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final bio = (a['bio'] ?? '').toString().toLowerCase();
      final ex = astrologerExpertiseLine(a).toLowerCase();
      return name.contains(q) || bio.contains(q) || ex.contains(q);
    }).toList();
  }

  void _openConsultation(
    Map<String, dynamic> item, {
    ConsultationCallMode initialCallMode = ConsultationCallMode.none,
  }) {
    final uid = AppSession.userId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start a consultation.')),
      );
      return;
    }
    final rawId = item['id'];
    final aid = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (aid == null || aid <= 0) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ConsultationRoomScreen(
          astrologerId: aid,
          peerDisplayName: item['name']?.toString() ?? 'Astrologer',
          initialCallMode: initialCallMode,
        ),
      ),
    );
  }

  Future<void> _pickCallModeAndOpen(Map<String, dynamic> item) async {
    final choice = await showModalBottomSheet<ConsultationCallMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: const Text('Voice call'),
              onTap: () => Navigator.pop(ctx, ConsultationCallMode.voice),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Video call'),
              onTap: () => Navigator.pop(ctx, ConsultationCallMode.video),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    _openConsultation(item, initialCallMode: choice);
  }

  Future<void> _loadRecentCalls() async {
    final uid = AppSession.userId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _callsLoading = false;
          _recentCalls = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _callsLoading = true;
        _callsError = null;
      });
    }
    try {
      final res = await ConsultationApi.listCallHistory(userId: uid, limit: 40);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _recentCalls = List<Map<String, dynamic>>.from(
            (res['data'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          _callsLoading = false;
          _callsError = null;
        });
      } else {
        setState(() {
          _callsLoading = false;
          _callsError = res['message']?.toString();
          _recentCalls = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _callsLoading = false;
          _callsError = e.toString();
          _recentCalls = [];
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadAstrologers(),
      _loadRecentCalls(),
    ]);
  }

  void _openCallHistoryRow(Map<String, dynamic> row) {
    final sid = row['sessionId'];
    final sessionId = sid is int ? sid : int.tryParse(sid?.toString() ?? '');
    if (sessionId == null || sessionId <= 0) return;
    final name = row['peerName']?.toString() ?? 'Chat';
    final aid = row['astrologerId'];
    final astroId = aid is int ? aid : int.tryParse(aid?.toString() ?? '');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ConsultationRoomScreen(
          existingSessionId: sessionId,
          astrologerId: astroId,
          peerDisplayName: name,
        ),
      ),
    );
  }

  String _peerInitial(String? name) {
    final t = name?.trim();
    if (t == null || t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  String _formatDurationSeconds(dynamic raw) {
    final s = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (s == null || s < 0) return '—';
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    if (m < 60) return '${m}m ${r.toString().padLeft(2, '0')}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm}m';
  }

  String _formatEndedLabel(dynamic v) {
    if (v == null) return '';
    final dt = v is String ? DateTime.tryParse(v) : null;
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(local.year, local.month, local.day);
    if (d == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return 'Today $h:$min';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _loadAstrologers() async {
    setState(() {
      _astroLoading = true;
      _astroError = null;
    });
    try {
      final res = await AstrologerApi.list();
      if (!mounted) return;
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _astrologers = List<Map<String, dynamic>>.from(
            (res['data'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          _astroLoading = false;
          _astroError = null;
        });
      } else {
        setState(() {
          _astroLoading = false;
          _astroError = res['message']?.toString() ?? 'Could not load astrologers';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _astroLoading = false;
        _astroError = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _refreshAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            color: AppTheme.primaryTextColor,
          ),
          Expanded(
            child: Text(
              'Astrologers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.inputBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search astrologers, skills…',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.secondaryTextColor,
              size: 24,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildRecentCallsSlivers(BuildContext context) {
    if (_callsLoading && _recentCalls.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      );
    }
    if (_recentCalls.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Text(
            _callsError ??
                'No recent calls yet. Start a voice or video call from an astrologer card.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final row = _recentCalls[i];
          final isVideo = (row['callType']?.toString() ?? '') == 'video';
          final outgoing = row['direction']?.toString() == 'outgoing';
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Text(
                _peerInitial(row['peerName']?.toString()),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              row['peerName']?.toString() ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${isVideo ? 'Video' : 'Voice'} · ${_formatDurationSeconds(row['durationSeconds'])} · '
              '${outgoing ? 'Outgoing' : 'Incoming'} · ${_formatEndedLabel(row['endedAt'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _openCallHistoryRow(row),
          );
        },
        childCount: _recentCalls.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryTextColor,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildLiveAstrologers(BuildContext context) {
    if (_astroLoading) {
      return SizedBox(
        height: 132,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }
    final list = _filteredAstrologers;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          _astroError != null
              ? _astroError!
              : 'No astrologers match your search.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final strip = list.length > 16 ? list.sublist(0, 16) : list;
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: strip.length,
        itemBuilder: (context, i) {
          final a = strip[i];
          return AstrologerLiveCircle(
            data: a,
            onTap: () => _openConsultation(a),
          );
        },
      ),
    );
  }

  Widget _buildListSlivers(BuildContext context) {
    if (_astroLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          child: Center(
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Loading astrologers…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_astroError != null && _astrologers.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.secondaryTextColor),
              const SizedBox(height: 12),
              Text(
                _astroError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppPrimaryButton.icon(
                onPressed: _loadAstrologers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredAstrologers;
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48, color: AppTheme.hintTextColor),
              const SizedBox(height: 12),
              Text(
                'No astrologers found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Try another search or pull to refresh.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final item = list[i];
          return AstrologerFeedCard(
            data: item,
            onChat: () => _openConsultation(item),
            onCall: () => _pickCallModeAndOpen(item),
          );
        },
        childCount: list.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceColor,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: _refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildSectionHeader('Recent calls')),
              _buildRecentCallsSlivers(context),
              SliverToBoxAdapter(child: _buildSectionHeader('Live Astrologers')),
              SliverToBoxAdapter(child: _buildLiveAstrologers(context)),
              SliverToBoxAdapter(child: _buildSectionHeader('Astrologers')),
              _buildListSlivers(context),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
