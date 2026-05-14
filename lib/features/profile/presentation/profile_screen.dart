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
    final stats = _ProfileProgressStats(
      watchedHours: watchedHours,
      completedEpisodes: completedEpisodes,
      series: series,
      streak: streak,
      favorites: favorites.length,
      savedEpisodes: saved.length,
      weeklyEpisodes: _weeklyCompletedEpisodes(history),
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
          padding: const EdgeInsets.fromLTRB(30, 18, 30, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                icon: Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
            const SizedBox(height: 4),
            const _ProfileHeader(),
            const SizedBox(height: 22),
            MarathonHud(
              session: marathon,
              onReset: () => ref.read(marathonProvider.notifier).reset(),
            ),
            if (marathon.isActive) const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.28,
              children: [
                _ProfileStat(
                  icon: Icons.timer_rounded,
                  label: 'Tiempo total',
                  value: '$watchedHours h',
                  color: AppColors.accent2,
                  iconBackground: AppColors.accent.withValues(alpha: 0.22),
                ),
                _ProfileStat(
                  icon: Icons.check_rounded,
                  label: 'Eps vistos',
                  value: '$completedEpisodes',
                  color: AppColors.success,
                  iconBackground: AppColors.success.withValues(alpha: 0.18),
                ),
                _ProfileStat(
                  icon: Icons.receipt_long_rounded,
                  label: 'Series totales',
                  value: '$series',
                  color: AppColors.warning,
                  iconBackground: AppColors.warning.withValues(alpha: 0.18),
                ),
                _ProfileStat(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Racha días',
                  value: '$streak',
                  color: AppColors.accent2,
                  iconBackground: AppColors.accent.withValues(alpha: 0.22),
                  valuePrefix: streak > 0 ? '🔥 ' : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LevelCard(level: level),
            const SizedBox(height: 18),
            const _SectionTitle('Logros recientes'),
            const SizedBox(height: 10),
            _AchievementGrid(achievements: achievements),
            const SizedBox(height: 18),
            const _SectionTitle('Retos semanales'),
            const SizedBox(height: 10),
            Column(
              children: challenges
                  .map((challenge) => _ChallengeCard(challenge: challenge))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Géneros favoritos'),
            const SizedBox(height: 10),
            if (genres.isEmpty)
              const Text(
                'Agrega favoritos para construir tus estadísticas.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              )
            else
              Column(
                children: genres.take(5).map((entry) {
                  final max = genres.first.value;
                  final percent = max == 0 ? 0.0 : entry.value / max;
                  return _GenreBar(name: entry.key, percent: percent);
                }).toList(),
              ),
            const SizedBox(height: 26),
            const _SectionTitle('Actividad (últimas 10 semanas)'),
            const SizedBox(height: 10),
            _ActivityGrid(activity: recentActivity),
            const SizedBox(height: 12),
            const _ActivityLegend(),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => context.go('/history'),
              icon: Icon(Icons.history_rounded, size: 18),
              label: const Text('Ver historial completo'),
            ),
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
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return history.where((item) {
      if (!item.completed) return false;
      final updatedAt = DateTime.tryParse(item.updatedAt);
      return updatedAt != null && !updatedAt.isBefore(weekStart);
    }).length;
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

  // Cuenta exclusiva del creador hasta implementar auth
  static const _ownerAccount = true;

  double get percent => nextLevelXp == 0 ? 1.0 : currentXp / nextLevelXp;
  int get remainingXp => nextLevelXp == 0 ? 0 : (nextLevelXp - currentXp).clamp(0, nextLevelXp);

  factory _LevelProgress.fromStats(_ProfileProgressStats stats) {
    if (_ownerAccount) {
      return _LevelProgress(
        level: 999,
        currentXp: stats.xp,
        nextLevelXp: 0,
        title: '👑 Creador',
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

  const _Achievement({
    required this.icon,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.color,
  });

  static List<_Achievement> fromStats(_ProfileProgressStats stats) {
    // En modo owner los logros se muestran bloqueados hasta implementar auth
    const owner = _LevelProgress._ownerAccount;
    return [
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        name: 'Maratonista',
        description: '5 eps en una semana',
        unlocked: owner || stats.weeklyEpisodes >= 5,
        color: AppColors.error,
      ),
      _Achievement(
        icon: Icons.calendar_month_rounded,
        name: 'Racha ${stats.streak}',
        description: '7 días seguidos',
        unlocked: owner || stats.streak >= 7,
        color: AppColors.warning,
      ),
      _Achievement(
        icon: Icons.explore_rounded,
        name: 'Explorador',
        description: '5 géneros favoritos',
        unlocked: owner || stats.favoriteGenres >= 5,
        color: AppColors.accent2,
      ),
      _Achievement(
        icon: Icons.check_circle_rounded,
        name: 'Constante',
        description: '25 eps vistos',
        unlocked: owner || stats.completedEpisodes >= 25,
        color: AppColors.success,
      ),
      _Achievement(
        icon: Icons.bookmark_rounded,
        name: 'Curador',
        description: '10 favoritos',
        unlocked: owner || stats.favorites >= 10,
        color: AppColors.accent,
      ),
      _Achievement(
        icon: Icons.offline_pin_rounded,
        name: 'Offline',
        description: '5 eps guardados',
        unlocked: owner || stats.savedEpisodes >= 5,
        color: AppColors.success,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: AppColors.accent2,
          child: Text(
            'M',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Michael',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'Otaku de corazón 🎮',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 3),
              Text(
                'Miembro desde enero 2024',
                style: TextStyle(color: AppColors.accent2, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconBackground;
  final String? valuePrefix;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconBackground,
    this.valuePrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    if (valuePrefix != null)
                      TextSpan(
                        text: valuePrefix,
                        style: TextStyle(fontSize: 18),
                      ),
                    TextSpan(text: value),
                  ],
                ),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final _LevelProgress level;

  const _LevelCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final percent = level.percent.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accent2],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LVL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${level.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.nextLevelXp == 0
                          ? '${level.currentXp} XP · Nivel máximo'
                          : '${level.currentXp} / ${level.nextLevelXp} XP · faltan ${level.remainingXp}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.accent2),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  final List<_Achievement> achievements;

  const _AchievementGrid({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: achievements
          .map((achievement) => _AchievementTile(achievement: achievement))
          .toList(),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final color = achievement.unlocked
        ? achievement.color
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: achievement.unlocked
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: achievement.unlocked
              ? achievement.color.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Opacity(
        opacity: achievement.unlocked ? 1 : 0.55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(achievement.icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              achievement.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final _WeeklyChallenge challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: challenge.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(challenge.icon, color: challenge.color, size: 19),
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
                challenge.completed ? 'Listo' : '+${challenge.xp} XP',
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
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.percent,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      challenge.completed
                          ? AppColors.success
                          : AppColors.accent2,
                    ),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String name;
  final double percent;

  const _GenreBar({required this.name, required this.percent});

  @override
  Widget build(BuildContext context) {
    final safePercent = percent.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: safePercent,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(AppColors.accent2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '${(safePercent * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityGrid extends StatelessWidget {
  final Map<DateTime, int> activity;

  const _ActivityGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 69));
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(70, (index) {
        final day = start.add(Duration(days: index));
        final count = activity[day] ?? 0;
        final color = switch (count) {
          0 => AppColors.surface2,
          1 => AppColors.accent.withValues(alpha: 0.65),
          2 || 3 => AppColors.accent2.withValues(alpha: 0.8),
          _ => AppColors.accent2,
        };
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  const _ActivityLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _LegendPill(label: 'Ninguno', color: AppColors.surface2),
        _LegendPill(label: 'Poco', color: AppColors.accent),
        _LegendPill(label: 'Mucho', color: AppColors.accent2),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
