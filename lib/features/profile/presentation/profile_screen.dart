import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final favorites = ref.watch(favoritesProvider);
    final saved = downloads.where((item) => item.isSavedOnDevice).toList();
    final series = {
      for (final item in saved) item.albumKey,
      for (final item in favorites) item.url,
    }.length;
    final minutes = saved.length * 24;
    final genreCounts = <String, int>{};
    for (final anime in favorites) {
      for (final genre in anime.genres.take(3)) {
        genreCounts.update(genre, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final genres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _ProfileHero(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.45,
                children: [
                  _ProfileStat(
                    icon: Icons.timer_rounded,
                    label: 'Tiempo total',
                    value: _formatMinutes(minutes),
                    color: AppColors.accent2,
                  ),
                  _ProfileStat(
                    icon: Icons.check_rounded,
                    label: 'Eps vistos',
                    value: '${saved.length}',
                    color: AppColors.success,
                  ),
                  _ProfileStat(
                    icon: Icons.video_library_rounded,
                    label: 'Series',
                    value: '$series',
                    color: AppColors.warning,
                  ),
                  _ProfileStat(
                    icon: Icons.favorite_rounded,
                    label: 'Favoritos',
                    value: '${favorites.length}',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Generos favoritos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            if (genres.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Agrega favoritos para construir tus estadisticas.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: genres.take(5).map((entry) {
                    final max = genres.first.value;
                    return _GenreBar(
                      name: entry.key,
                      percent: max == 0 ? 0 : entry.value / max,
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Actividad reciente',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(42, (index) {
                  final level = _activityLevel(saved.length, index);
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColors.surface2,
                        AppColors.accent2,
                        level,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static double _activityLevel(int saved, int index) {
    if (saved == 0) return 0.0;
    final value = (saved + index * 3) % 5;
    return value / 4;
  }

  static String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.accent,
            child: Text(
              'M',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
                SizedBox(height: 2),
                Text(
                  'Tu actividad en AnimeRoll',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String name;
  final double percent;

  const _GenreBar({required this.name, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percent.clamp(0, 1),
                minHeight: 7,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(percent * 100).round()}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
