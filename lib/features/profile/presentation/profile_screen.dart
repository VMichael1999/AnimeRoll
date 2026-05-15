import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/achievement_banner.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../history/data/watch_history_provider.dart';
import '../../marathon/data/marathon_provider.dart';
import '../../marathon/presentation/marathon_hud.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _seenKey = 'seenAchievements_v1';
  Set<String> _seenAchievements = {};
  bool _seenLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_seenKey) ?? [];
    if (mounted) {
      setState(() {
        _seenAchievements = raw.toSet();
        _seenLoaded = true;
      });
    }
  }

  Future<void> _checkNewAchievements(List<_Achievement> achievements) async {
    if (!_seenLoaded) return;
    final newlyUnlocked = achievements
        .where((a) => a.unlocked && !_seenAchievements.contains(a.name))
        .toList();
    if (newlyUnlocked.isEmpty) return;

    final allSeen = {..._seenAchievements, ...newlyUnlocked.map((a) => a.name)};
    setState(() => _seenAchievements = allSeen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenKey, allSeen.toList());

    for (final achievement in newlyUnlocked) {
      if (!mounted) return;
      AchievementBanner.show(
        context,
        title: '¡Nuevo logro desbloqueado!',
        subtitle: '${achievement.name} · ${achievement.description}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(watchHistoryProvider);
    final marathon = ref.watch(marathonProvider);
    final saved = downloads.where((item) => item.isSavedOnDevice).toList();
    final watchedMs = history.fold<int>(
      0,
      (total, item) =>
          total + (item.completed ? item.durationMs : item.positionMs),
    );
    final watchedHours = watchedMs ~/ Duration.millisecondsPerHour;
    final completedEpisodes = history.where((item) => item.completed).length;
    final series = {
      for (final item in saved) item.albumKey,
      for (final item in favorites) item.url,
      for (final item in history) item.animeUrl,
    }.where((item) => item.isNotEmpty).length;
    final streak = _watchStreak(history);
    final recentActivity = _activityByDay(history);
    final genres = _favoriteGenres(favorites);
    final weeklyEpisodes = _weeklyCompletedEpisodes(history);
    final weeklyHours = _weeklyHours(history);
    final stats = _ProfileProgressStats(
      watchedHours: watchedHours,
      completedEpisodes: completedEpisodes,
      series: series,
      streak: streak,
      favorites: favorites.length,
      savedEpisodes: saved.length,
      weeklyEpisodes: weeklyEpisodes,
      favoriteGenres: genres.length,
    );
    final level = _LevelProgress.fromStats(stats);
    final achievements = _Achievement.fromStats(stats);
    final challenges = _WeeklyChallenge.fromStats(stats);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewAchievements(achievements);
    });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TopBar(),
            _ProfileHero(level: level),
            MarathonHud(
              session: marathon,
              onReset: () => ref.read(marathonProvider.notifier).reset(),
            ),
            const _SectionHeader(title: 'Accesos rápidos'),
            _QuickActions(
              favoritesCount: favorites.length,
              downloadsCount: saved.length,
              historyCount: history.length,
              watchlistCount: favorites.length,
            ),
            const _SectionHeader(title: 'Estadísticas'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.32,
                children: [
                  _StatCard(
                    icon: Icons.timer_rounded,
                    label: 'Tiempo total',
                    value: '$watchedHours',
                    valueSuffix: 'h',
                    color: AppColors.accent2,
                    iconBg: AppColors.accent.withValues(alpha: 0.22),
                    glow: AppColors.accent2.withValues(alpha: 0.25),
                    trend: weeklyHours > 0 ? '+${weeklyHours}h' : null,
                  ),
                  _StatCard(
                    icon: Icons.check_rounded,
                    label: 'Eps vistos',
                    value: '$completedEpisodes',
                    color: AppColors.success,
                    iconBg: AppColors.success.withValues(alpha: 0.18),
                    glow: AppColors.success.withValues(alpha: 0.18),
                    trend: weeklyEpisodes > 0 ? '+$weeklyEpisodes' : null,
                  ),
                  _StatCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Series totales',
                    value: '$series',
                    color: AppColors.warning,
                    iconBg: AppColors.warning.withValues(alpha: 0.18),
                    glow: AppColors.warning.withValues(alpha: 0.18),
                  ),
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Racha',
                    value: '$streak',
                    valueSuffix: 'd',
                    color: AppColors.error,
                    iconBg: AppColors.error.withValues(alpha: 0.18),
                    glow: AppColors.error.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),
            _SectionHeader(
              title: 'Logros',
              action: 'Ver todos (${achievements.length})',
              onAction: () {},
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: achievements
                    .map((a) => _AchievementTile(achievement: a))
                    .toList(),
              ),
            ),
            const _SectionHeader(title: 'Retos semanales'),
            ...challenges.map((c) => _ChallengeCard(challenge: c)),
            const _SectionHeader(title: 'Géneros favoritos'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: genres.isEmpty
                  ? const Text(
                      'Agrega favoritos para construir tus estadísticas.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    )
                  : Column(
                      children: genres.take(5).toList().asMap().entries.map((e) {
                        final max = genres.first.value;
                        final percent =
                            max == 0 ? 0.0 : e.value.value / max;
                        return _GenreRow(
                          rank: e.key + 1,
                          name: e.value.key,
                          percent: percent,
                        );
                      }).toList(),
                    ),
            ),
            const _SectionHeader(
              title: 'Actividad',
              trailing: 'Últimas 10 semanas',
            ),
            _ActivitySection(activity: recentActivity),
            const SizedBox(height: 16),
            _HistoryCard(
              episodes: completedEpisodes,
              series: series,
              onTap: () => context.go('/history'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static List<MapEntry<String, int>> _favoriteGenres(List<dynamic> favorites) {
    final counts = <String, int>{};
    for (final anime in favorites) {
      for (final genre in anime.genres.take(3)) {
        counts.update(genre, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  static Map<DateTime, int> _activityByDay(List<WatchHistoryEntry> history) {
    final counts = <DateTime, int>{};
    for (final item in history) {
      final updatedAt = DateTime.tryParse(item.updatedAt);
      if (updatedAt == null) continue;
      final date = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
      counts.update(date, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static int _weeklyCompletedEpisodes(List<WatchHistoryEntry> history) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return history.where((item) {
      if (!item.completed) return false;
      final updatedAt = DateTime.tryParse(item.updatedAt);
      return updatedAt != null && !updatedAt.isBefore(weekStart);
    }).length;
  }

  static int _weeklyHours(List<WatchHistoryEntry> history) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final ms = history.where((item) {
      final updatedAt = DateTime.tryParse(item.updatedAt);
      return updatedAt != null && !updatedAt.isBefore(weekStart);
    }).fold<int>(
      0,
      (total, item) =>
          total + (item.completed ? item.durationMs : item.positionMs),
    );
    return ms ~/ Duration.millisecondsPerHour;
  }

  static int _watchStreak(List<WatchHistoryEntry> history) {
    final activity = _activityByDay(history);
    if (activity.isEmpty) return 0;
    final today = DateTime.now();
    var day = DateTime(today.year, today.month, today.day);
    var streak = 0;
    while (activity.containsKey(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _ProfileProgressStats {
  final int watchedHours;
  final int completedEpisodes;
  final int series;
  final int streak;
  final int favorites;
  final int savedEpisodes;
  final int weeklyEpisodes;
  final int favoriteGenres;

  const _ProfileProgressStats({
    required this.watchedHours,
    required this.completedEpisodes,
    required this.series,
    required this.streak,
    required this.favorites,
    required this.savedEpisodes,
    required this.weeklyEpisodes,
    required this.favoriteGenres,
  });

  int get xp =>
      completedEpisodes * 80 +
      watchedHours * 18 +
      streak * 120 +
      series * 45 +
      favorites * 20 +
      savedEpisodes * 30;
}

class _LevelProgress {
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final String title;

  const _LevelProgress({
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.title,
  });

  static const _ownerAccount = true;

  double get percent => nextLevelXp == 0 ? 1.0 : currentXp / nextLevelXp;
  int get remainingXp =>
      nextLevelXp == 0 ? 0 : (nextLevelXp - currentXp).clamp(0, nextLevelXp);
  bool get isMax => nextLevelXp == 0;

  factory _LevelProgress.fromStats(_ProfileProgressStats stats) {
    if (_ownerAccount) {
      return _LevelProgress(
        level: 999,
        currentXp: stats.xp,
        nextLevelXp: 0,
        title: 'Creador · Miembro premium',
      );
    }
    final level = (stats.xp ~/ 500).clamp(1, 99);
    final currentXp = stats.xp % 500;
    final title = switch (level) {
      >= 20 => 'Leyenda del anime',
      >= 12 => 'Otaku veterano',
      >= 6 => 'Explorador activo',
      _ => 'Nuevo aventurero',
    };
    return _LevelProgress(
      level: level,
      currentXp: currentXp,
      nextLevelXp: 500,
      title: title,
    );
  }
}

class _Achievement {
  final IconData icon;
  final String name;
  final String description;
  final bool unlocked;
  final Color color;
  final int current;
  final int target;

  const _Achievement({
    required this.icon,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.color,
    required this.current,
    required this.target,
  });

  double get progress =>
      target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  static List<_Achievement> fromStats(_ProfileProgressStats stats) {
    return [
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        name: 'Maratonista',
        description: '5 eps/semana',
        unlocked: stats.weeklyEpisodes >= 5,
        color: AppColors.error,
        current: stats.weeklyEpisodes,
        target: 5,
      ),
      _Achievement(
        icon: Icons.calendar_month_rounded,
        name: 'Racha de 7',
        description: '7 días seguidos',
        unlocked: stats.streak >= 7,
        color: AppColors.warning,
        current: stats.streak,
        target: 7,
      ),
      _Achievement(
        icon: Icons.explore_rounded,
        name: 'Explorador',
        description: '5 géneros favoritos',
        unlocked: stats.favoriteGenres >= 5,
        color: AppColors.accent2,
        current: stats.favoriteGenres,
        target: 5,
      ),
      _Achievement(
        icon: Icons.check_circle_rounded,
        name: 'Constante',
        description: '25 eps vistos',
        unlocked: stats.completedEpisodes >= 25,
        color: AppColors.success,
        current: stats.completedEpisodes,
        target: 25,
      ),
      _Achievement(
        icon: Icons.bookmark_rounded,
        name: 'Curador',
        description: '10 favoritos',
        unlocked: stats.favorites >= 10,
        color: AppColors.accent,
        current: stats.favorites,
        target: 10,
      ),
      _Achievement(
        icon: Icons.offline_pin_rounded,
        name: 'Offline',
        description: '5 eps guardados',
        unlocked: stats.savedEpisodes >= 5,
        color: AppColors.success,
        current: stats.savedEpisodes,
        target: 5,
      ),
    ];
  }
}

class _WeeklyChallenge {
  final IconData icon;
  final String title;
  final String description;
  final int current;
  final int target;
  final int xp;
  final Color color;

  const _WeeklyChallenge({
    required this.icon,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.xp,
    required this.color,
  });

  double get percent => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
  bool get completed => current >= target;

  static List<_WeeklyChallenge> fromStats(_ProfileProgressStats stats) {
    return [
      _WeeklyChallenge(
        icon: Icons.local_fire_department_rounded,
        title: 'Maratón exprés',
        description: 'Ve 10 episodios esta semana',
        current: stats.weeklyEpisodes,
        target: 10,
        xp: 500,
        color: AppColors.error,
      ),
      _WeeklyChallenge(
        icon: Icons.category_rounded,
        title: 'Fuera de zona',
        description: 'Marca 5 géneros favoritos',
        current: stats.favoriteGenres,
        target: 5,
        xp: 300,
        color: AppColors.accent2,
      ),
      _WeeklyChallenge(
        icon: Icons.download_done_rounded,
        title: 'Biblioteca lista',
        description: 'Guarda 3 episodios offline',
        current: stats.savedEpisodes,
        target: 3,
        xp: 250,
        color: AppColors.success,
      ),
    ];
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Mi perfil',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => context.go('/settings'),
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.accent2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile hero ──────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final _LevelProgress level;
  const _ProfileHero({required this.level});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          height: 280,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.35),
                    AppColors.accent2.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  _AvatarRing(level: level.level),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Michael',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '✨',
                              style: TextStyle(
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                      color: AppColors.accent2
                                          .withValues(alpha: 0.6),
                                      blurRadius: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          level.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.accent2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Otaku de corazón · Desde ene 2024',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accent2.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.accent2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _XpBar(level: level),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final int level;
  const _AvatarRing({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  AppColors.accent,
                  AppColors.accent2,
                  AppColors.accent,
                  AppColors.accent2,
                  AppColors.accent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg,
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.accent2],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: Text(
                '👑 $level',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final _LevelProgress level;
  const _XpBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final percent = level.percent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${level.currentXp} XP',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: level.isMax
                        ? ' · Nivel máximo'
                        : ' · faltan ${level.remainingXp}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '${(percent * 100).round()}%',
              style: TextStyle(
                color: AppColors.accent2,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accent2],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent2.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final String? trailing;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.action,
    this.trailing,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.accent, AppColors.accent2],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$action →',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final int favoritesCount;
  final int downloadsCount;
  final int historyCount;
  final int watchlistCount;

  const _QuickActions({
    required this.favoritesCount,
    required this.downloadsCount,
    required this.historyCount,
    required this.watchlistCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.favorite_rounded,
              label: 'Favoritos',
              badge: favoritesCount > 0 ? '$favoritesCount' : null,
              onTap: () => context.go('/favorites'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.download_done_rounded,
              label: 'Descargas',
              badge: downloadsCount > 0 ? '$downloadsCount' : null,
              onTap: () => context.go('/downloads'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.history_rounded,
              label: 'Historial',
              badge: historyCount > 0 ? '$historyCount' : null,
              onTap: () => context.go('/history'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.bookmark_added_rounded,
              label: 'Pendiente',
              onTap: () => context.go('/watchlist'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: AppColors.accent2, size: 16),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.bg, width: 1.5),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? valueSuffix;
  final Color color;
  final Color iconBg;
  final Color glow;
  final String? trend;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconBg,
    required this.glow,
    this.valueSuffix,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glow, Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: value),
                      if (valueSuffix != null)
                        TextSpan(
                          text: valueSuffix,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ]),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (trend != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  trend!,
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Achievement tile ──────────────────────────────────────────────────────────

class _AchievementTile extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? AppColors.accent2.withValues(alpha: 0.4)
              : AppColors.border,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: AppColors.accent2.withValues(alpha: 0.15),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? AppColors.accent2.withValues(alpha: 0.18)
                      : AppColors.textSecondary.withValues(alpha: 0.1),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: AppColors.accent2.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  achievement.icon,
                  color: unlocked
                      ? AppColors.accent2
                      : AppColors.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: unlocked
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                achievement.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 3,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent2),
                  ),
                ),
              ],
            ],
          ),
          if (unlocked)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Challenge card ────────────────────────────────────────────────────────────

class _ChallengeCard extends StatelessWidget {
  final _WeeklyChallenge challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: challenge.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(challenge.icon, color: challenge.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                challenge.completed ? 'Listo ✓' : '+${challenge.xp} XP',
                style: TextStyle(
                  color: challenge.completed
                      ? AppColors.success
                      : AppColors.accent2,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(height: 6, color: AppColors.border),
                      FractionallySizedBox(
                        widthFactor: challenge.percent,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: challenge.completed
                                ? null
                                : LinearGradient(
                                    colors: [
                                      AppColors.accent,
                                      AppColors.accent2
                                    ],
                                  ),
                            color: challenge.completed
                                ? AppColors.success
                                : null,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${challenge.current.clamp(0, challenge.target)}',
                      style: TextStyle(
                        color: challenge.completed
                            ? AppColors.success
                            : AppColors.accent2,
                      ),
                    ),
                    TextSpan(text: '/${challenge.target}'),
                  ],
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Genre row ────────────────────────────────────────────────────────────────

class _GenreRow extends StatelessWidget {
  final int rank;
  final String name;
  final double percent;

  const _GenreRow({
    required this.rank,
    required this.name,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final safe = percent.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(height: 6, color: AppColors.border),
                  FractionallySizedBox(
                    widthFactor: safe,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accent2],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${(safe * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity section ──────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final Map<DateTime, int> activity;

  const _ActivitySection({required this.activity});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 69));
    final months = _monthLabels(start, today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months
                .map((m) => Text(
                      m,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 10;
              const gap = 4.0;
              final cellSize =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: List.generate(70, (index) {
                  final day = start.add(Duration(days: index));
                  final count = activity[day] ?? 0;
                  final color = switch (count) {
                    0 => AppColors.surface2,
                    1 => AppColors.accent.withValues(alpha: 0.4),
                    2 || 3 => AppColors.accent2.withValues(alpha: 0.7),
                    _ => AppColors.accent2,
                  };
                  return Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: count >= 4
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.accent2.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Menos',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              ...[
                AppColors.surface2,
                AppColors.accent.withValues(alpha: 0.4),
                AppColors.accent2.withValues(alpha: 0.7),
                AppColors.accent2,
              ].map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
              const SizedBox(width: 5),
              Text(
                'Más',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<String> _monthLabels(DateTime start, DateTime end) {
    const monthNames = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    final months = <int>{};
    var cursor = DateTime(start.year, start.month);
    while (!cursor.isAfter(end)) {
      months.add(cursor.month - 1);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months.map((m) => monthNames[m]).toList();
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final int episodes;
  final int series;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.episodes,
    required this.series,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppColors.accent2,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ver historial completo',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$episodes episodios · $series series',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.accent2,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
