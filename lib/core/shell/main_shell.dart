import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/settings/data/settings_provider.dart';
import '../theme/app_theme.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context, bool isHentaila) {
    final location = GoRouterState.of(context).uri.path;
    if (!isHentaila && location.startsWith('/schedule')) return 1;
    if (location.startsWith('/search')) return isHentaila ? 1 : 2;
    if (location.startsWith('/favorites')) return isHentaila ? 2 : 3;
    if (location.startsWith('/watchlist')) return isHentaila ? 3 : 4;
    if (location.startsWith('/downloads')) return isHentaila ? 4 : 5;
    if (location.startsWith('/settings')) return isHentaila ? 5 : 6;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHentaila = ref.watch(providerPrefProvider) == 'hentaila.com';
    final index = _currentIndex(context, isHentaila);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        backgroundColor: AppColors.surface,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (i) {
          if (isHentaila) {
            switch (i) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/search');
              case 2:
                context.go('/favorites');
              case 3:
                context.go('/watchlist');
              case 4:
                context.go('/downloads');
              case 5:
                context.go('/settings');
            }
            return;
          }
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
              context.go('/watchlist');
            case 5:
              context.go('/downloads');
            case 6:
              context.go('/settings');
          }
        },
        items: isHentaila ? _hentailaItems : _defaultItems,
      ),
    );
  }

  static const _defaultItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_rounded),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_month_rounded),
      label: 'Horario',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Buscar'),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite_rounded),
      label: 'Favoritos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bookmark_rounded),
      label: 'Mi Lista',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.download_rounded),
      label: 'Descargas',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_rounded),
      label: 'Ajustes',
    ),
  ];

  static const _hentailaItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_rounded),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Buscar'),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite_rounded),
      label: 'Favoritos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bookmark_rounded),
      label: 'Mi Lista',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.download_rounded),
      label: 'Descargas',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_rounded),
      label: 'Ajustes',
    ),
  ];
}
