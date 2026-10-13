import 'package:flutter/material.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/dashboard/creator_dashboard_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/more/creator_more_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/podcast_management/podcast_list_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/requests/request_list_screen.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/wallet/wallet_screen.dart';

class CreatorMainShell extends StatefulWidget {
  final VoidCallback? onTheme;
  final VoidCallback? onLogout;

  const CreatorMainShell({super.key, this.onTheme, this.onLogout});

  @override
  State<CreatorMainShell> createState() => _CreatorMainShellState();
}

class _CreatorMainShellState extends State<CreatorMainShell> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screens = [
      CreatorDashboardScreen(onNavigateTab: _navigateToTab),
      const PodcastListScreen(),
      const RequestListScreen(),
      const WalletScreen(),
      CreatorMoreScreen(onTheme: widget.onTheme, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        unselectedItemColor: isDark ? const Color(0xFFC8C2BA) : const Color(0xFF5A5248),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.podcasts_outlined),
            activeIcon: Icon(Icons.podcasts_rounded),
            label: 'Podcast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Đơn đặt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Ví tiền',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_outlined),
            activeIcon: Icon(Icons.more_horiz_rounded),
            label: 'Tiện ích',
          ),
        ],
      ),
    );
  }
}
