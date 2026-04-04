import 'package:flutter/material.dart';
import '../../core/session/app_session.dart';
import '../../core/session/dashboard_mode_store.dart';
import '../../core/theme/app_theme.dart';

/// Drawer for the astrologer partner shell; includes switch back to user app.
class AstrologerDrawer extends StatelessWidget {
  const AstrologerDrawer({
    super.key,
    required this.onSwitchToUserApp,
  });

  final VoidCallback onSwitchToUserApp;

  static const String _version = 'Version 1.1.465';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.switch_account_rounded,
                color: AppTheme.primaryColor),
            title: const Text(
              'Switch to user app',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Browse astrologers, wallet & services',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(context).pop();
              onSwitchToUserApp();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _tile(context, 'Profile & rates', Icons.person_outline_rounded),
                  _tile(context, 'Sessions & history', Icons.history_rounded),
                  _tile(context, 'Payouts', Icons.account_balance_wallet_outlined),
                  _tile(context, 'Help & policies', Icons.help_outline_rounded),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.errorColor,
              size: 22,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await AppSession.clear();
              await DashboardModeStore.clear();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              _version,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final name = AppSession.displayName;
    final phone = AppSession.phoneLine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.nightlight_round,
                color: AppTheme.onPrimaryColor, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(phone, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Astrologer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
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

  Widget _tile(BuildContext context, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppTheme.primaryTextColor),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      onTap: () => Navigator.of(context).pop(),
    );
  }
}
