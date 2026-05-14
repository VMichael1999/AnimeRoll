import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../history/data/watch_history_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(watchHistoryProvider);
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
