import 'package:flutter/material.dart';
import '../../core/api/user_api.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_primary_button.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = AppSession.userId;
    if (id == null) {
      setState(() {
        _loading = false;
        _user = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await UserApi.getUser(id);
      if (!mounted) return;
      final ok = res['success'] == true || (res['_statusCode'] as int?) == 200;
      if (ok && res['data'] is Map) {
        final u = Map<String, dynamic>.from(res['data'] as Map);
        await AppSession.setUser(u);
        setState(() {
          _user = u;
          _loading = false;
        });
      } else {
        setState(() {
          _user = AppSession.user;
          _loading = false;
          _error = res['message']?.toString() ?? 'Could not load profile';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = AppSession.user;
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openEdit(Map<String, dynamic> u) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: Map<String, dynamic>.from(u)),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _user = AppSession.user);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (AppSession.userId == null)
              SliverFillRemaining(child: _buildSignedOut(context))
            else
              _buildProfileSlivers(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: AppTheme.primaryTextColor,
      elevation: 0,
      title: const Text('Profile'),
      actions: [
        if (!_loading && AppSession.userId != null)
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit profile',
            onPressed: () {
              final u = _user ?? AppSession.user;
              if (u != null && u.isNotEmpty) _openEdit(u);
            },
          ),
      ],
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.person_off_outlined, size: 56, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 28),
          Text(
            'You’re not signed in',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Log in with your mobile number to view and edit your profile.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.secondaryTextColor,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            width: double.infinity,
            height: 52,
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('Go to login'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSlivers(BuildContext context) {
    final u = _user ?? AppSession.user ?? {};
    if (_error != null && u.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.errorColor)),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final name = u['name']?.toString().trim();
    final display = (name != null && name.isNotEmpty) ? name : 'Your name';
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    final phone = _phoneLine(u);
    final memberSince = _formatMemberSince(u['createdAt']);

    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryDark,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Material(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      display,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (memberSince != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        memberSince,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.hintTextColor,
                            ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openEdit(u),
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          label: const Text('Edit profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryDark,
                            side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              children: [
                _modernSection(
                  context,
                  title: 'Contact',
                  icon: Icons.alternate_email_rounded,
                  children: [
                    _infoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _emptyDash(u['email']),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _modernSection(
                  context,
                  title: 'Personal',
                  icon: Icons.favorite_outline_rounded,
                  children: [
                    _infoTile(
                      icon: Icons.wc_rounded,
                      label: 'Gender',
                      value: _gender(u['gender']),
                    ),
                    _divider(),
                    _infoTile(
                      icon: Icons.schedule_rounded,
                      label: 'Know birth time',
                      value: _boolLabel(u['knowBirthTime']),
                    ),
                    _divider(),
                    _infoTile(
                      icon: Icons.access_time_rounded,
                      label: 'Birth time',
                      value: _emptyDash(u['birthTime']),
                    ),
                    _divider(),
                    _infoTile(
                      icon: Icons.event_rounded,
                      label: 'Birth date',
                      value: _emptyDash(u['birthDate']),
                    ),
                    _divider(),
                    _infoTile(
                      icon: Icons.place_outlined,
                      label: 'Birth place',
                      value: _emptyDash(u['birthPlace']),
                    ),
                    _divider(),
                    _infoTile(
                      icon: Icons.translate_rounded,
                      label: 'Languages',
                      value: _languages(u['languages']),
                      isLast: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _phoneLine(Map<String, dynamic> u) {
    final cc = u['countryCode']?.toString() ?? '+91';
    final ph = u['phone']?.toString() ?? '';
    if (ph.isEmpty) return '—';
    return '$cc $ph';
  }

  static String? _formatMemberSince(dynamic createdAt) {
    if (createdAt == null) return null;
    final s = createdAt.toString();
    if (s.length < 10) return null;
    try {
      final d = DateTime.parse(s.substring(0, 10));
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return 'Member since ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return null;
    }
  }

  Widget _modernSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.25),
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppTheme.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, isLast ? 18 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.secondaryTextColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryTextColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1),
    );
  }

  static String _emptyDash(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  static String _gender(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _boolLabel(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    return v.toString();
  }

  static String _languages(dynamic v) {
    if (v == null) return '—';
    if (v is List) {
      if (v.isEmpty) return '—';
      return v.map((e) => e.toString()).join(', ');
    }
    return v.toString();
  }
}
