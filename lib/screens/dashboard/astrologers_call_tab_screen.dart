import 'package:flutter/material.dart';

import '../../core/api/astrologer_api.dart';
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
    _loadAstrologers();
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
          onRefresh: _loadAstrologers,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
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
