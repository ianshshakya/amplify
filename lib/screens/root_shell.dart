import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'ask_julu_screen.dart';

/// The responsive app shell.
/// Adapts between Desktop (Sidebar + Bottom Player) and Mobile (Bottom Nav + Mini Player).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    AskJuluScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    child: Container(
                      color: AppColors.surface,
                      child: _screens[_index],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Desktop full-width mini-player (which acts as the persistent player)
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _SidebarItem(
            icon: Icons.home_filled,
            label: 'Home',
            isSelected: _index == 0,
            onTap: () => setState(() => _index = 0),
          ),
          _SidebarItem(
            icon: Icons.search,
            label: 'Search',
            isSelected: _index == 1,
            onTap: () => setState(() => _index = 1),
          ),
          _SidebarItem(
            icon: Icons.library_music,
            label: 'Your Library',
            isSelected: _index == 2,
            onTap: () => setState(() => _index = 2),
          ),
          _SidebarItem(
            icon: Icons.auto_awesome,
            label: 'Ask Julu',
            isSelected: _index == 3,
            onTap: () => setState(() => _index = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_index],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
              BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Julu'),
            ],
            type: BottomNavigationBarType.fixed, // Ensure >3 items show correctly
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
