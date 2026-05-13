import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/downloads')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent2,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home');
            case 1: context.go('/search');
            case 2: context.go('/downloads');
            case 3: context.go('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Descargas'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
