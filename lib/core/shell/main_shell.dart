import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/settings/data/settings_provider.dart';
import '../../shared/utils/provider_capabilities.dart';
import '../theme/app_theme.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _drawerController = AwesomeDrawerBarController();

  int _currentIndex(BuildContext context, {required bool showSchedule}) {
    final location = GoRouterState.of(context).uri.path;
    if (showSchedule && location.startsWith('/schedule')) return 1;
    if (location.startsWith('/search')) return showSchedule ? 2 : 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Mostramos el horario solo cuando el proveedor activo lo soporta.
    // Antes era `!= 'hentaila.com'`, lo que dejaba el botón visible para
    // proveedores como MonosChinos que tampoco exponen schedule real.
    final showSchedule =
        ProviderId.fromDomain(ref.watch(providerPrefProvider)).supportsSchedule;
    final location = GoRouterState.of(context).uri.path;
    if (!showSchedule && location.startsWith('/schedule')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }
    final index = _currentIndex(context, showSchedule: showSchedule);
    return AwesomeDrawerBar(
      type: StyleState.scaleRight,
      controller: _drawerController,
      menuScreen: _DrawerMenu(
        onNavigate: (route) {
          _drawerController.close?.call();
          context.go(route);
        },
      ),
      mainScreen: Scaffold(
        body: widget.child,
        floatingActionButton: FloatingActionButton.small(
          heroTag: 'drawer-menu',
          tooltip: 'Menu',
          backgroundColor: AppColors.surface,
          foregroundColor: Theme.of(context).colorScheme.secondary,
          onPressed: () => _drawerController.toggle?.call(),
          child: const Icon(Icons.menu_rounded),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          backgroundColor: AppColors.surface,
          selectedItemColor: Theme.of(context).colorScheme.secondary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (i) {
            final route = showSchedule
                ? ['/home', '/schedule', '/search'][i]
                : ['/home', '/search'][i];
            context.go(route);
          },
          items: showSchedule ? _bottomItems : _bottomItemsWithoutSchedule,
        ),
      ),
      borderRadius: 24,
      showShadow: true,
      angle: -12,
      backgroundColor: AppColors.surface2,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      slideWidth: MediaQuery.of(context).size.width * 0.65,
    );
  }

  static const _bottomItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_rounded),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_month_rounded),
      label: 'Horario',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Buscar'),
  ];

  static const _bottomItemsWithoutSchedule = [
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_rounded),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Buscar'),
  ];
}

class _DrawerMenu extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const _DrawerMenu({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final menuBackground = theme.scaffoldBackgroundColor;
    final menuDivider = colorScheme.outlineVariant;
    final menuText = colorScheme.onSurface;
    final menuMuted = colorScheme.onSurface.withValues(alpha: 0.6);
    final location = GoRouterState.of(context).uri.path;

    return Material(
      color: menuBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 34, 26, 26),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: theme.cardColor,
                    child: Text(
                      'AR',
                      style: TextStyle(
                        color: menuText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AnimeRoll',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: menuText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppColors.warning,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tu biblioteca',
                              style: TextStyle(
                                color: menuMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _DrawerDivider(color: menuDivider, height: 18),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 18),
                children: [
                  _DrawerItem(
                    icon: Icons.favorite_rounded,
                    label: 'Favoritos',
                    active: location.startsWith('/favorites'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/favorites'),
                  ),
                  _DrawerItem(
                    icon: Icons.bookmark_rounded,
                    label: 'Mi Lista',
                    active: location.startsWith('/watchlist'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/watchlist'),
                  ),
                  _DrawerItem(
                    icon: Icons.download_rounded,
                    label: 'Descargas',
                    active: location.startsWith('/downloads'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/downloads'),
                  ),
                  _DrawerItem(
                    icon: Icons.video_library_rounded,
                    label: 'Biblioteca',
                    active: location.startsWith('/library'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/library'),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Historial',
                    active: location.startsWith('/history'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/history'),
                  ),
                  _DrawerDivider(color: menuDivider),
                  _DrawerItem(
                    icon: Icons.person_rounded,
                    label: 'Perfil',
                    active: location.startsWith('/profile'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/profile'),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Ajustes',
                    active: location.startsWith('/settings'),
                    color: menuText,
                    mutedColor: menuMuted,
                    onTap: () => onNavigate('/settings'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 58, right: 30, bottom: 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AnimeRoll',
                  style: TextStyle(
                    color: menuMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final Color mutedColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.active = false,
    required this.color,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 58, right: 26),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(
                icon,
                color: active ? AppColors.accent2 : mutedColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 22),
            if (active)
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.accent2 : color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  final Color color;
  final double height;

  const _DrawerDivider({required this.color, this.height = 34});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: 1,
      color: color,
      indent: 58,
      endIndent: 30,
    );
  }
}
