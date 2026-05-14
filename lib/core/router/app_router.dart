import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/detail/presentation/detail_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../shell/main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, _) => const HomeScreen()),
        GoRoute(
          path: '/schedule',
          builder: (context, _) => const ScheduleScreen(),
        ),
        GoRoute(path: '/search', builder: (context, _) => const SearchScreen()),
        GoRoute(
          path: '/downloads',
          builder: (context, _) => const DownloadsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, _) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/detail',
      builder: (context, state) {
        final animeUrl = state.uri.queryParameters['url'] ?? '';
        return DetailScreen(animeUrl: animeUrl);
      },
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final episodeUrl = state.uri.queryParameters['url'] ?? '';
        final title = state.uri.queryParameters['title'] ?? '';
        final animeUrl = state.uri.queryParameters['animeUrl'] ?? '';
        return PlayerScreen(
          episodeUrl: episodeUrl,
          title: title,
          animeUrl: animeUrl,
        );
      },
    ),
  ],
);
