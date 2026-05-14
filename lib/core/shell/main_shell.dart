import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/schedule')) return 1;
    if (location.startsWith('/search')) return 2;
    if (location.startsWith('/favorites')) return 3;
    if (location.startsWith('/downloads')) return 4;
    if (location.startsWith('/settings')) return 5;
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
            case 0:
              context.go('/home');
            case 1:
              context.go('/schedule');
            case 2:
              context.go('/search');
            case 3:
              context.go('/favorites');
            case 4:
              context.go('/downloads');
            case 5:
              context.go('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Horario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_rounded),
            label: 'Descargas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
