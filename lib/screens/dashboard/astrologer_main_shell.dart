import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../consultation/consultation_sessions_list_screen.dart';
import 'astrologer_drawer.dart';
import 'astrologer_home_screen.dart';
import 'dashboard_placeholder_tab.dart';

/// Partner app shell for users with [AppSession.isAstrologer].
class AstrologerMainShell extends StatefulWidget {
  const AstrologerMainShell({
    super.key,
    required this.onSwitchToUserApp,
  });

  final VoidCallback onSwitchToUserApp;

  @override
  State<AstrologerMainShell> createState() => _AstrologerMainShellState();
}

class _AstrologerMainShellState extends State<AstrologerMainShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _tabs = [
    _NavItem('Home', Icons.home_rounded),
    _NavItem('Requests', Icons.inbox_rounded),
    _NavItem('Earnings', Icons.payments_rounded),
    _NavItem('Chat', Icons.chat_bubble_rounded),
    _NavItem('Profile', Icons.person_rounded),
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
          child: AstrologerDrawer(
            onSwitchToUserApp: widget.onSwitchToUserApp,
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const AstrologerHomeScreen(),
            const DashboardPlaceholderTab(
              title: 'Requests',
              icon: Icons.inbox_rounded,
            ),
            const DashboardPlaceholderTab(
              title: 'Earnings',
              icon: Icons.payments_rounded,
            ),
            const ConsultationSessionsListScreen(
              perspective: 'astrologer',
              includeClosed: true,
            ),
            const DashboardPlaceholderTab(
              title: 'Profile',
              icon: Icons.person_rounded,
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
                        horizontal: 8,
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
                              fontSize: 10,
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
