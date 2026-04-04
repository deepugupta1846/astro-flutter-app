import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../consultation/consultation_sessions_list_screen.dart';
import 'app_drawer.dart';
import 'astrologers_call_tab_screen.dart';
import 'dashboard_placeholder_tab.dart';
import 'dashboard_screen.dart';

/// Customer app shell: bottom tabs + drawer (browse astrologers, wallet, etc.).
class UserMainShell extends StatefulWidget {
  const UserMainShell({super.key, this.onSwitchToAstrologerApp});

  /// When non-null, drawer shows entry to open the astrologer partner dashboard.
  final VoidCallback? onSwitchToAstrologerApp;

  @override
  State<UserMainShell> createState() => _UserMainShellState();
}

class _UserMainShellState extends State<UserMainShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _tabs = [
    _NavItem('Home', Icons.home_rounded),
    _NavItem('Chat', Icons.chat_bubble_rounded),
    _NavItem('Live', Icons.live_tv_rounded),
    _NavItem('Call', Icons.call_rounded),
    _NavItem('Remedies', Icons.favorite_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.78;
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: DrawerThemeData(
          width: drawerWidth,
          backgroundColor: AppTheme.surfaceColor,
        ),
      ),
      child: Scaffold(
        drawer: Drawer(
          child: AppDrawer(
            onSwitchToAstrologerDashboard: widget.onSwitchToAstrologerApp,
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const DashboardScreen(),
            const ConsultationSessionsListScreen(
              includeClosed: true,
            ),
            const DashboardPlaceholderTab(
              title: 'Live',
              icon: Icons.live_tv_rounded,
            ),
            const AstrologersCallTabScreen(),
            const DashboardPlaceholderTab(
              title: 'Remedies',
              icon: Icons.favorite_rounded,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabs.length, (i) {
                  final item = _tabs[i];
                  final isSelected = _currentIndex == i;
                  return InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 24,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.secondaryTextColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  const _NavItem(this.title, this.icon);
}
