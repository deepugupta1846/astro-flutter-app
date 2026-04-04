import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/session/app_session.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    this.onSwitchToAstrologerDashboard,
  });

  /// When set (typically for [AppSession.isAstrologer] on the user shell), shows
  /// a top entry to open the partner / astrologer dashboard.
  final VoidCallback? onSwitchToAstrologerDashboard;

  static const String _appVersion = 'Version 1.1.465';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(context),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildMenuItems(context),
                  const SizedBox(height: 16),
                  _buildAlsoAvailableOn(context),
                  const SizedBox(height: 24),
                  _buildVersion(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final name = AppSession.displayName;
    final phone = AppSession.phoneLine.isEmpty
        ? (AppSession.isLoggedIn ? '' : 'Sign in to sync profile')
        : AppSession.phoneLine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openProfile(context),
              borderRadius: BorderRadius.circular(28),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.person_rounded, color: AppTheme.onPrimaryColor, size: 36),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openProfile(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.secondaryTextColor),
                        ],
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'View full profile',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.primaryTextColor,
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/profile');
  }

  Widget _buildMenuItems(BuildContext context) {
    final partner = onSwitchToAstrologerDashboard;
    final items = [
      _DrawerItem('Home', Icons.home_rounded),
      _DrawerItem('Book a Pooja', Icons.soup_kitchen_rounded, showNew: true),
      _DrawerItem('Customer Support Chat', Icons.headset_mic_rounded),
      _DrawerItem('Wallet Transactions', Icons.account_balance_wallet_rounded),
      _DrawerItem('Redeem Gift Card', Icons.card_giftcard_rounded),
      _DrawerItem('Order History', Icons.history_rounded),
      _DrawerItem('AstroRemedy', Icons.shopping_bag_rounded),
      _DrawerItem('Astrology Blog', Icons.menu_book_rounded),
      _DrawerItem('Chat with Astrologers', Icons.psychology_rounded),
      _DrawerItem('My Following', Icons.person_add_rounded),
      _DrawerItem('My Kundli', Icons.grid_view_rounded),
      _DrawerItem('Free Services', Icons.local_offer_rounded),
      _DrawerItem('Settings', Icons.settings_rounded),
      _DrawerItem('Logout', Icons.logout_rounded, isLogout: true),
    ];
    return Column(
      children: [
        if (partner != null) ...[
          ListTile(
            leading: const Icon(
              Icons.auto_awesome,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            title: const Text(
              'Astrologer / Partner dashboard',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            subtitle: Text(
              'Manage sessions, earnings & availability',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(context).pop();
              partner();
            },
          ),
          const Divider(height: 1),
        ],
        ...items.map((e) => _drawerTile(context, e)),
      ],
    );
  }

  Widget _drawerTile(BuildContext context, _DrawerItem item) {
    final isLogout = item.isLogout;
    return ListTile(
      leading: Icon(
        item.icon,
        size: 22,
        color: isLogout ? AppTheme.errorColor : AppTheme.primaryTextColor,
      ),
      title: Row(
        children: [
          Text(
            item.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isLogout ? AppTheme.errorColor : AppTheme.primaryTextColor,
            ),
          ),
          if (item.showNew) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'New',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        Navigator.of(context).pop();
        if (isLogout) {
          await AppSession.clear();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      },
    );
  }

  Widget _buildAlsoAvailableOn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Also available on',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _socialIcon(Icons.apple, const Color(0xFF000000)),
              _socialIcon(Icons.android, const Color(0xFF3DDC84)),
              _socialIcon(Icons.play_circle_fill, const Color(0xFFFF0000)),
              _socialIcon(Icons.facebook, const Color(0xFF1877F2)),
              _socialIcon(Icons.camera_alt, const Color(0xFFE4405F)),
              _socialIcon(Icons.business_center, const Color(0xFF0A66C2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildVersion(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        _appVersion,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.successColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String title;
  final IconData icon;
  final bool showNew;
  final bool isLogout;
  _DrawerItem(this.title, this.icon, {this.showNew = false, this.isLogout = false});
}
