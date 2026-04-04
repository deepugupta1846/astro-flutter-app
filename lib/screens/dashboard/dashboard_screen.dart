import 'package:flutter/material.dart';

import '../../core/api/astrologer_api.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_primary_button.dart';
import '../consultation/consultation_room_screen.dart';
import 'astrologer_public_views.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _loadController;
  late AnimationController _pulseController;

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
    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _loadController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _animatedSection({
    required int index,
    required int total,
    required Widget child,
  }) {
    const stagger = 0.06;
    final start = (index * stagger).clamp(0.0, 1.0);
    final end = ((index + 1) * stagger).clamp(0.0, 1.0);
    final range = end - start;
    return AnimatedBuilder(
      animation: _loadController,
      builder: (context, _) {
        final t = range > 0
            ? ((_loadController.value - start) / range).clamp(0.0, 1.0)
            : 1.0;
        final curveT = Curves.easeOutCubic.transform(t);
        final opacity = curveT;
        final dy = 24 * (1 - curveT);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
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
            SliverToBoxAdapter(
              child: _animatedSection(index: 0, total: 12, child: _buildHeaderContent(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 1, total: 12, child: _buildSearchBar(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 2, total: 12, child: _buildCashbackBanner(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 3, total: 12, child: _buildServiceIcons(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 4, total: 12, child: _buildPromoBanner1(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 5, total: 12, child: _buildSectionHeaderContent(context, 'Live Astrologers', 'View All')),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 6, total: 12, child: _buildLiveAstrologers(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 7, total: 12, child: _buildGotQuestionsBanner(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 8, total: 12, child: _buildChatCallButtons(context)),
            ),
            SliverToBoxAdapter(
              child: _animatedSection(index: 9, total: 12, child: _buildSectionHeaderContent(context, 'Astrologers', 'View All')),
            ),
            _buildAstrologerList(context),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          _ScaleTap(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.person_rounded, color: AppTheme.onPrimaryColor, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi ${AppSession.firstName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _walletChip(context),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            onPressed: () {},
            color: AppTheme.primaryTextColor,
            style: IconButton.styleFrom(backgroundColor: AppTheme.backgroundColor),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () {},
            color: AppTheme.primaryTextColor,
            style: IconButton.styleFrom(backgroundColor: AppTheme.backgroundColor),
          ),
        ],
      ),
    );
  }

  Widget _walletChip(BuildContext context) {
    return _ScaleTap(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.inputBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 18, color: AppTheme.primaryTextColor),
                const SizedBox(width: 6),
                const Text('₹ 30', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.primaryTextColor,
                )),
                const SizedBox(width: 4),
                Icon(Icons.add_circle_rounded, size: 20, color: AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '50% Cashback',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
            ),
          ],
        ),
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
            prefixIcon: Icon(Icons.search_rounded,
                color: AppTheme.secondaryTextColor, size: 24),
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

  Widget _buildCashbackBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final scale = 1.0 + (_pulseController.value * 0.01);
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.18),
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '50% Cashback!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ON NEXT RECHARGE',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _ScaleTap(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'RECHARGE NOW',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceIcons(BuildContext context) {
    final services = <_ServiceItem>[
      _ServiceItem('Daily Horoscope', Icons.wb_sunny_rounded),
      _ServiceItem('Free Kundli', Icons.grid_view_rounded),
      _ServiceItem('Kundli Matching', Icons.favorite_rounded),
      _ServiceItem('Astrology Blog', Icons.menu_book_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(services.length, (i) {
          final e = services[i];
          return _AnimatedServiceIcon(
            label: e.label,
            icon: e.icon,
            delay: 0.1 + (i * 0.05),
            loadController: _loadController,
            onTap: () {},
          );
        }),
      ),
    );
  }

  Widget _buildPromoBanner1(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _ScaleTap(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceColor,
                AppTheme.surfaceElevated,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.inputBorderColor.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What will my future be in the next 5 years?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask Astrologer',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _ScaleTap(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text('Chat Now', style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.onPrimaryColor,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.25),
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: const Icon(Icons.person_rounded, size: 48, color: AppTheme.primaryTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderContent(BuildContext context, String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
              letterSpacing: -0.3,
            ),
          ),
          _ScaleTap(
            onTap: () {},
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
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
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + (i * 50)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(16 * (1 - value), 0),
                  child: child,
                ),
              );
            },
            child: AstrologerLiveCircle(
              data: a,
              onTap: () {},
            ),
          );
        },
      ),
    );
  }

  Widget _buildGotQuestionsBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: const Icon(Icons.phone_android_rounded, color: Colors.white54, size: 38),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Got any questions?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chat with Astrologer @₹5/min',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ScaleTap(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text('Chat Now', style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.onPrimaryColor,
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatCallButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _ScaleTap(
              onTap: () {},
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_rounded, size: 22, color: AppTheme.onPrimaryColor),
                    SizedBox(width: 10),
                    Text('Chat with Astrologer', style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.onPrimaryColor,
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ScaleTap(
              onTap: () {},
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_rounded, size: 22, color: AppTheme.onPrimaryColor),
                    SizedBox(width: 10),
                    Text('Call with Astrologer', style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.onPrimaryColor,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAstrologerList(BuildContext context) {
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
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + (i * 60).clamp(0, 400)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: AstrologerFeedCard(
              data: item,
              onChat: () => _openConsultation(item),
              onCall: () => _pickCallModeAndOpen(item),
            ),
          );
        },
        childCount: list.length,
      ),
    );
  }
}

class _ServiceItem {
  final String label;
  final IconData icon;
  const _ServiceItem(this.label, this.icon);
}

class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTap({required this.child, required this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class _AnimatedServiceIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final double delay;
  final AnimationController loadController;
  final VoidCallback onTap;

  const _AnimatedServiceIcon({
    required this.label,
    required this.icon,
    required this.delay,
    required this.loadController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loadController,
      builder: (context, _) {
        final t = ((loadController.value - delay) / 0.2).clamp(0.0, 1.0);
        final curveT = Curves.elasticOut.transform(t);
        final scale = curveT;
        final opacity = (loadController.value - delay).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: _ScaleTap(
              onTap: onTap,
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryDark,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: AppTheme.onPrimaryColor, size: 30),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 76,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
